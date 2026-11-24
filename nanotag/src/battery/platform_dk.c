/*
 * Copyright (c) 2024 Nordic Semiconductor ASA
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

/*
 * nice!nano v2 battery sensing.
 *
 * Unlike the stock DK platform (which only simulates a battery level), this reads the real LiPo
 * voltage. On the nice!nano v2 the battery feeds VDDH, so we sample the SoC-internal VDDHDIV5 input
 * (VDDH / 5) — no external divider, pin or enable GPIO. The ADC channel is defined in the board
 * overlay under the `zephyr,user` node.
 *
 * Caveat: VDDH rises while the board is charging over USB, so the reported level reads high on USB
 * and is only accurate on battery.
 */

#include <zephyr/kernel.h>
#include <zephyr/drivers/adc.h>

#include <bluetooth/services/fast_pair/fmdn.h>

#include "app_battery.h"
#include "app_battery_priv.h"

#include <zephyr/logging/log.h>
LOG_MODULE_DECLARE(fp_fmdn, LOG_LEVEL_INF);

/* VDDHDIV5 samples VDDH divided by 5. */
#define VBATT_VDDH_SCALE 5

/* ponytail: LiPo voltage -> percent is a straight line between these two knobs; tune per cell.
 * Find Hub only buckets the percent into Normal/Low/Critical, so exactness isn't important. */
#define BATTERY_FULL_MV  4200
#define BATTERY_EMPTY_MV 3300

/* How often to re-measure. */
#define BATTERY_POLL_INTERVAL K_SECONDS(60)

static const struct adc_dt_spec vbatt_adc = ADC_DT_SPEC_GET(DT_PATH(zephyr_user));

static void battery_poll_work_handle(struct k_work *work);
static K_WORK_DELAYABLE_DEFINE(battery_poll_work, battery_poll_work_handle);

static int battery_vddh_mv_read(int32_t *vddh_mv)
{
	int err;
	int16_t sample;
	struct adc_sequence sequence = {
		.buffer = &sample,
		.buffer_size = sizeof(sample),
	};

	(void) adc_sequence_init_dt(&vbatt_adc, &sequence);

	err = adc_read_dt(&vbatt_adc, &sequence);
	if (err) {
		return err;
	}

	int32_t mv = sample;

	err = adc_raw_to_millivolts_dt(&vbatt_adc, &mv);
	if (err) {
		return err;
	}

	*vddh_mv = mv * VBATT_VDDH_SCALE;

	return 0;
}

static uint8_t battery_percentage_get(int32_t vddh_mv)
{
	if (vddh_mv <= BATTERY_EMPTY_MV) {
		return 0;
	}
	if (vddh_mv >= BATTERY_FULL_MV) {
		return 100;
	}

	return (uint8_t) (((vddh_mv - BATTERY_EMPTY_MV) * 100) /
			  (BATTERY_FULL_MV - BATTERY_EMPTY_MV));
}

static void battery_measure_and_propagate(void)
{
	int err;
	int32_t vddh_mv;
	uint8_t percentage_level;

	err = battery_vddh_mv_read(&vddh_mv);
	if (err) {
		LOG_ERR("Battery: VDDH read failed (err %d)", err);
		return;
	}

	percentage_level = battery_percentage_get(vddh_mv);

	err = bt_fast_pair_fmdn_battery_level_set(percentage_level);
	if (err) {
		LOG_ERR("FMDN: bt_fast_pair_fmdn_battery_level_set failed (err %d)", err);
		return;
	}

	LOG_INF("Battery: VDDH %d mV (high while USB-charging)", vddh_mv);
	app_battery_level_log(percentage_level);
}

static void battery_poll_work_handle(struct k_work *work)
{
	battery_measure_and_propagate();
	(void) k_work_reschedule(&battery_poll_work, BATTERY_POLL_INTERVAL);
}

int app_battery_init(void)
{
	int err;

	if (!adc_is_ready_dt(&vbatt_adc)) {
		LOG_ERR("Battery: ADC controller not ready");
		return -ENODEV;
	}

	err = adc_channel_setup_dt(&vbatt_adc);
	if (err) {
		LOG_ERR("Battery: adc_channel_setup_dt failed (err %d)", err);
		return err;
	}

	battery_measure_and_propagate();
	(void) k_work_reschedule(&battery_poll_work, BATTERY_POLL_INTERVAL);

	return 0;
}
